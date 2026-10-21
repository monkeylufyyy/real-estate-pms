/**
 * Builds the lease agreement PDF with jsPDF (https://github.com/parallax/jsPDF).
 * Kept free of Salesforce imports so it can be unit tested with a fake jsPDF.
 */

const MARGIN = 20;
const LINE_HEIGHT = 6;

export function formatDate(isoDate) {
    if (!isoDate) {
        return '';
    }
    const [year, month, day] = String(isoDate).split('-').map(Number);
    return new Date(year, month - 1, day).toLocaleDateString('en-GB', {
        day: '2-digit',
        month: 'short',
        year: 'numeric'
    });
}

export function formatMoney(amount, currencyCode) {
    if (amount === null || amount === undefined) {
        return '';
    }
    try {
        // "code" display keeps the text inside the Latin-1 range supported by jsPDF's built-in fonts.
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: currencyCode || 'USD',
            currencyDisplay: 'code'
        })
            .format(amount)
            .replace(/ /g, ' ');
    } catch (e) {
        return String(amount);
    }
}

export function pdfFileName(details) {
    return `${details.leaseNumber || 'Lease-Agreement'}.pdf`;
}

export function buildLeasePdf(JsPDF, details, currencyCode) {
    const doc = new JsPDF({ unit: 'mm', format: 'a4' });
    const pageWidth = doc.internal.pageSize.getWidth();
    const pageHeight = doc.internal.pageSize.getHeight();
    const contentWidth = pageWidth - MARGIN * 2;
    let y = MARGIN;

    const ensureSpace = (needed) => {
        if (y + needed > pageHeight - MARGIN) {
            doc.addPage();
            y = MARGIN;
        }
    };

    const heading = (text) => {
        ensureSpace(14);
        y += 4;
        doc.setFont('helvetica', 'bold');
        doc.setFontSize(12);
        doc.text(text, MARGIN, y);
        y += 2;
        doc.setLineWidth(0.3);
        doc.line(MARGIN, y, pageWidth - MARGIN, y);
        y += LINE_HEIGHT;
    };

    const row = (label, value) => {
        const lines = doc.splitTextToSize(String(value || '-'), contentWidth - 45);
        ensureSpace(lines.length * LINE_HEIGHT);
        doc.setFont('helvetica', 'bold');
        doc.setFontSize(10);
        doc.text(`${label}:`, MARGIN, y);
        doc.setFont('helvetica', 'normal');
        doc.text(lines, MARGIN + 45, y);
        y += lines.length * LINE_HEIGHT;
    };

    // Title
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(20);
    doc.text('LEASE AGREEMENT', pageWidth / 2, y, { align: 'center' });
    y += 8;
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(11);
    doc.text(`Agreement No. ${details.leaseNumber || ''}`, pageWidth / 2, y, { align: 'center' });
    y += 6;

    heading('Parties');
    row('Landlord', 'Property Management Team');
    row('Tenant', details.tenantName);
    row('Tenant email', details.tenantEmail);
    row('Tenant phone', details.tenantPhone);

    heading('Property');
    row('Property', details.propertyName);
    row('Address', details.propertyAddress);

    heading('Lease term and rent');
    row('Start date', formatDate(details.startDate));
    row('End date', formatDate(details.endDate));
    row('Monthly rent', formatMoney(details.monthlyRent, currencyCode));

    heading('Terms and conditions');
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(10);
    const termLines = doc.splitTextToSize(details.terms || 'No additional terms were recorded.', contentWidth);
    termLines.forEach((line) => {
        ensureSpace(LINE_HEIGHT);
        doc.text(line, MARGIN, y);
        y += LINE_HEIGHT - 1;
    });

    // Signature block
    ensureSpace(45);
    y += 18;
    doc.setLineWidth(0.3);
    doc.line(MARGIN, y, MARGIN + 70, y);
    doc.line(pageWidth - MARGIN - 70, y, pageWidth - MARGIN, y);
    y += 5;
    doc.setFontSize(9);
    doc.text('Tenant signature and date', MARGIN, y);
    doc.text('Landlord signature and date', pageWidth - MARGIN - 70, y);

    // Page numbers
    const pageCount = doc.getNumberOfPages();
    for (let page = 1; page <= pageCount; page++) {
        doc.setPage(page);
        doc.setFontSize(8);
        doc.text(`Page ${page} of ${pageCount}`, pageWidth / 2, pageHeight - 10, { align: 'center' });
    }
    return doc;
}
